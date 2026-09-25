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
    ['security.view']          = true,
    ['security.monitor']       = true,

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

Config.permissions = {
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
    ['security.view']          = 'mod',
    ['security.monitor']       = 'admin',

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

Config.menusections = {
    { id = 'self',    label = 'Self' },
    { id = 'players', label = 'Players' },
    { id = 'security', label = 'Security' },
    { id = 'vehicle', label = 'Vehicles' },
    { id = 'props',   label = 'Props & Entities' },
    { id = 'garage',  label = 'Garage' },
    { id = 'staff',    label = 'Staff' },
}

Config.security = {
    maxMonitorMinutes = 10,
    detectionRetention = 100,
    timelineRetention = 100,
    historyDays = 90,
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

    modules = {
        propSpam     = true,
        vehicleSpam  = true,
        pedSpam      = true,
        explosions   = true,
        blacklist    = true,
        spawnLogging = true,
        clientChecks = true,
        silentAim    = true,
        pingGate     = true,
        godmode      = true,
        punch        = true,
        heartbeat    = true,
        banClips     = true,
        aimbot       = true,
        confidence   = true,
    },

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

    silentAim = {
        enabled          = true,
        action           = 'confidence',
        points           = 35,
        banLength        = 0,
        reason           = 'Silent aim',
        strikes          = 3,
        strikeWindow     = 60.0,

        lateralTolerance = 2.25,
        minAngle         = 2.0,
        maxAngle         = 35.0,
        minDistance      = 6.0,
        maxDistance      = 400.0,
        distanceSlack    = 0.0,

        useClientAim       = true,
        maxClientAimAgeMs  = 900,
        eyeHeight          = 0.6,

        useHitOffset  = true,
        maxHitOffset  = 1.5,

        latencyCompensation   = true,
        latencyFactor         = 1.0,
        maxCompensatedPing    = 1.0,
        maxCompensationMetres = 6.0,

        sampleCooldownMs = 150,
        skipInVehicle    = true,
        requireVisible   = true,
        joinGrace        = 30,
    },

    aimbot = {
        enabled   = true,
        action    = 'confidence',
        points    = 30,
        banLength = 0,
        reason    = 'Aimbot',

        sampleMs          = 20,
        windowMs          = 600,
        minSamples        = 6,
        maxPacked         = 900,
        reportCooldownMs  = 250,
        maxReportAgeMs    = 900,

        idleStep       = 0.35,
        maxGap         = 2,
        minSnapDegrees = 12.0,
        minSnapSamples = 4,
        lockCone       = 6.0,
        minDistance    = 4.0,
        eyeHeight      = 0.6,

        corridorDegrees = 1.5,

        smallSnap  = 5.0,
        largeSnap  = 90.0,
        maxAllowed = 100.0,
        minAllowed = 82.0,
        maxCorridor = 100.0,
        minCorridor = 88.0,
        curve      = 1.0,

        controller      = 'raise',
        controllerSlack = 1.25,

        snapSpeed = {
            enabled              = true,
            points               = 25,
            maxDegreesPerSecond  = 1400.0,
            minSnap              = 20.0,
            useLongestStep       = true,
        },

        teleport = {
            enabled        = true,
            points         = 45,
            maxStepDegrees = 25.0,
        },

        settle = {
            enabled = true,
            points  = 20,
            minMs   = 60,
            minSnap = 20.0,
        },

        overshoot = {
            enabled    = true,
            points     = 15,
            samples    = 12,
            maxAverage = 0.4,
            minSnap    = 25.0,
        },

        serverCheck = {
            enabled       = true,
            points        = 40,
            sampleMs      = 100,
            watchSeconds  = 20.0,
            slackMs       = 150,
            tolerance     = 2.5,
            minDifference = 25.0,
        },

        missing = {
            enabled   = true,
            shots     = 12,
            action    = 'kick',
            banLength = 0,
            reason    = 'TsivTools aim module is not answering',
        },
    },

    confidence = {
        enabled = true,

        window = 180.0,
        decay  = true,

        banAt     = 100,
        soloBanAt = 170,
        kickAt    = 0,
        alertAt   = 40,
        alertCooldown = 20.0,

        requireDistinctModules = 2,

        evidenceOnly = {
            punch = true,
        },

        banReason  = 'Anticheat confidence threshold',
        kickReason = 'Anticheat confidence threshold',
        banLength  = 0,

        maxEntries    = 200,
        defaultWeight = 20,

        weights = {
            silentaim   = 100,
            aimbot      = 100,
            snapspeed   = 90,
            settle      = 70,
            overshoot   = 60,
            aimmismatch = 100,
            teleport    = 110,
            godmode     = 110,
            punch       = 40,
        },
    },

    pingGate = {
        enabled   = true,
        maxPing   = 700,
        action    = 'block',
        strikes   = 25,
        window    = 30.0,
        banLength = 0,
        reason    = 'Shooting on an unplayable connection',
    },

    godmode = {
        enabled      = true,
        action       = 'confidence',
        points       = 45,
        banLength    = 0,
        reason       = 'Godmode',
        strikes      = 4,
        strikeWindow = 120.0,
        checkDelayMs = 900,
        joinGrace    = 45,
        skipExempt   = true,

        weapons = {
            'WEAPON_PISTOL',
            'WEAPON_PISTOL_MK2',
            'WEAPON_COMBATPISTOL',
            'WEAPON_APPISTOL',
            'WEAPON_HEAVYPISTOL',
            'WEAPON_VINTAGEPISTOL',
            'WEAPON_SNSPISTOL',
            'WEAPON_PISTOL50',
            'WEAPON_REVOLVER',
            'WEAPON_MICROSMG',
            'WEAPON_SMG',
            'WEAPON_SMG_MK2',
            'WEAPON_ASSAULTSMG',
            'WEAPON_COMBATPDW',
            'WEAPON_MACHINEPISTOL',
            'WEAPON_MINISMG',
            'WEAPON_ASSAULTRIFLE',
            'WEAPON_ASSAULTRIFLE_MK2',
            'WEAPON_CARBINERIFLE',
            'WEAPON_CARBINERIFLE_MK2',
            'WEAPON_ADVANCEDRIFLE',
            'WEAPON_SPECIALCARBINE',
            'WEAPON_BULLPUPRIFLE',
            'WEAPON_COMPACTRIFLE',
            'WEAPON_MG',
            'WEAPON_COMBATMG',
            'WEAPON_GUSENBERG',
            'WEAPON_PUMPSHOTGUN',
            'WEAPON_SAWNOFFSHOTGUN',
            'WEAPON_ASSAULTSHOTGUN',
            'WEAPON_BULLPUPSHOTGUN',
            'WEAPON_HEAVYSHOTGUN',
            'WEAPON_SNIPERRIFLE',
            'WEAPON_HEAVYSNIPER',
            'WEAPON_MARKSMANRIFLE',
            'WEAPON_UNARMED',
            'WEAPON_KNIFE',
            'WEAPON_BAT',
            'WEAPON_CROWBAR',
            'WEAPON_HAMMER',
            'WEAPON_MACHETE',
            'WEAPON_SWITCHBLADE',
            'WEAPON_BATTLEAXE',
        },
    },

    punch = {
        enabled          = true,
        action           = 'confidence',
        points           = 12,
        banLength        = 0,
        reason           = 'Melee spam',
        block            = true,
        minIntervalMs    = 300,
        victimIntervalMs = 450,
        multiTargets     = 3,
        multiWindow      = 2.0,
        strikes          = 8,
        strikeWindow     = 30.0,

        meleeWeapons = {
            'WEAPON_UNARMED',
            'WEAPON_KNIFE',
            'WEAPON_NIGHTSTICK',
            'WEAPON_HAMMER',
            'WEAPON_BAT',
            'WEAPON_GOLFCLUB',
            'WEAPON_CROWBAR',
            'WEAPON_BOTTLE',
            'WEAPON_DAGGER',
            'WEAPON_HATCHET',
            'WEAPON_KNUCKLE',
            'WEAPON_MACHETE',
            'WEAPON_FLASHLIGHT',
            'WEAPON_SWITCHBLADE',
            'WEAPON_POOLCUE',
            'WEAPON_WRENCH',
            'WEAPON_BATTLEAXE',
            'WEAPON_STONE_HATCHET',
        },
    },

    heartbeat = {
        enabled         = true,
        intervalSeconds = 15,
        graceSeconds    = 120,
        missTolerance   = 3,
        useToken        = true,
        action          = 'kick',
        banLength       = 0,
        reason          = 'TsivTools client stopped answering',
    },

    clips = {
        enabled        = true,
        mode           = 'relay',
        seconds        = 5,
        frames         = 3,
        quality        = 0.35,
        holdMs         = 7000,
        freezeTarget   = true,
        maxFrameBytes  = 700000,
        webhook        = '',
        webhookConvar  = 'tsivtoolsclipwebhook',
        username       = 'tsivtools',
    },

    pedCacheSeconds = 3.0,

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
