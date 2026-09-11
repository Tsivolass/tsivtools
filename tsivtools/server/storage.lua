TSIV.Storage = {}

local Storage = TSIV.Storage
local cache = {}
local dirty = {}
local useMysql = Config.Database.enabled

local function filePath(name)
    return ('data/%s.json'):format(name)
end

local function loadFile(name)
    if cache[name] then return cache[name] end

    local raw = LoadResourceFile(TSIV.resource, filePath(name))
    local data = nil

    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            data = decoded
        else
            SaveResourceFile(TSIV.resource, filePath(name .. '.corrupt'), raw, -1)
            print(('%sdata/%s.json could not be parsed, it was renamed to %s.corrupt.json and a fresh file was started')
                :format(Config.ConsolePrefix, name, name))
        end
    end

    cache[name] = data or {}
    return cache[name]
end

local function saveFile(name)
    local data = cache[name]
    if not data then return end
    SaveResourceFile(TSIV.resource, filePath(name), json.encode(data), -1)
end

CreateThread(function()
    while true do
        Wait(5000)
        for name in pairs(dirty) do
            saveFile(name)
            dirty[name] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= TSIV.resource then return end
    for name in pairs(dirty) do
        saveFile(name)
    end
end)

function Storage.Get(name)
    return loadFile(name)
end

function Storage.MarkDirty(name)
    dirty[name] = true
end

function Storage.Flush(name)
    if name then
        saveFile(name)
        dirty[name] = nil
    else
        for key in pairs(dirty) do
            saveFile(key)
            dirty[key] = nil
        end
    end
end

function Storage.UsingMysql()
    return useMysql
end

function Storage.Query(query, params)
    if not useMysql then return nil end
    return MySQL.query.await(query, params or {})
end

function Storage.Single(query, params)
    if not useMysql then return nil end
    return MySQL.single.await(query, params or {})
end

function Storage.Scalar(query, params)
    if not useMysql then return nil end
    return MySQL.scalar.await(query, params or {})
end

function Storage.Execute(query, params)
    if not useMysql then return nil end
    return MySQL.update.await(query, params or {})
end

function Storage.Insert(query, params)
    if not useMysql then return nil end
    return MySQL.insert.await(query, params or {})
end

local function ensureSchema()
    if not useMysql then return end

    Storage.Execute(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `identifiers` TEXT NULL,
            `name` VARCHAR(64) NOT NULL DEFAULT '',
            `reason` VARCHAR(255) NOT NULL DEFAULT '',
            `banned_by` VARCHAR(64) NOT NULL DEFAULT '',
            `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
            `expires_at` INT UNSIGNED NOT NULL DEFAULT 0,
            `active` TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.banTable))

    Storage.Execute(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `category` VARCHAR(32) NOT NULL,
            `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
            `actor` VARCHAR(64) NOT NULL DEFAULT '',
            `actor_name` VARCHAR(64) NOT NULL DEFAULT '',
            `target` VARCHAR(64) NOT NULL DEFAULT '',
            `target_name` VARCHAR(64) NOT NULL DEFAULT '',
            `message` TEXT NULL,
            `data` TEXT NULL,
            PRIMARY KEY (`id`),
            KEY `category` (`category`),
            KEY `actor` (`actor`),
            KEY `target` (`target`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.logTable))
end

CreateThread(function()
    if useMysql then
        local waited = 0
        while GetResourceState('oxmysql') ~= 'started' and waited < 10000 do
            Wait(250)
            waited = waited + 250
        end

        if GetResourceState('oxmysql') ~= 'started' then
            print(('%sConfig.Database.enabled is true but oxmysql is not started. Falling back to file storage.')
                :format(Config.ConsolePrefix))
            useMysql = false
        else
            ensureSchema()
            print(('%sstorage: mysql'):format(Config.ConsolePrefix))
        end
    else
        print(('%sstorage: file (tsivtools/data)'):format(Config.ConsolePrefix))
    end
end)
