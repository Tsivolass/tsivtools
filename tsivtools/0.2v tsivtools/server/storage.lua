tsivtools.Storage = {}

local Storage = tsivtools.Storage
local cache = {}
local dirty = {}
local useMysql = Config.Database.enabled

local function filePath(name)
    return ('data/%s.json'):format(name)
end

local oldKeys = {
    ['created_at'] = 'createdat',
    ['expires_at'] = 'expiresat',
    ['banned_by'] = 'bannedby',
    ['added_by'] = 'addedby',
    ['related_identifier'] = 'relatedidentifier',
    ['related_name'] = 'relatedname',
}

local function migrate(data)
    local changed = false
    local settings = {}

    for key, value in pairs(data) do
        if type(value) == 'table' then
            for old, new in pairs(oldKeys) do
                if value[old] ~= nil then
                    if value[new] == nil then value[new] = value[old] end
                    value[old] = nil
                    changed = true
                end
            end
        elseif type(key) == 'string' and key:sub(1, 8) == 'traffic_' then
            settings[#settings + 1] = key
        end
    end

    for _, key in ipairs(settings) do
        local new = 'traffic' .. key:sub(9)
        if data[new] == nil then data[new] = data[key] end
        data[key] = nil
        changed = true
    end

    return changed
end

local function loadFile(name)
    if cache[name] then return cache[name] end

    local raw = LoadResourceFile(tsivtools.resource, filePath(name))
    local data = nil

    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            data = decoded
        else
            SaveResourceFile(tsivtools.resource, filePath(name .. '.corrupt'), raw, -1)
            print(('%sdata/%s.json could not be parsed, it was renamed to %s.corrupt.json and a fresh file was started')
                :format(Config.ConsolePrefix, name, name))
        end
    end

    if data and migrate(data) then dirty[name] = true end
    cache[name] = data or {}
    return cache[name]
end

local function saveFile(name)
    local data = cache[name]
    if not data then return end
    SaveResourceFile(tsivtools.resource, filePath(name), json.encode(data), -1)
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
    if resource ~= tsivtools.resource then return end
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


local ready = false

function Storage.WaitReady()
    local waited = 0
    while not ready and waited < 15000 do
        Wait(100)
        waited = waited + 100
    end
    return ready
end

function Storage.UsingMysql()
    if not ready and coroutine.isyieldable() then Storage.WaitReady() end
    return useMysql
end


function Storage.Query(query, params)
    if not Storage.UsingMysql() then return nil end
    return MySQL.query.await(query, params or {})
end

function Storage.Single(query, params)
    if not Storage.UsingMysql() then return nil end
    return MySQL.single.await(query, params or {})
end

function Storage.Scalar(query, params)
    if not Storage.UsingMysql() then return nil end
    return MySQL.scalar.await(query, params or {})
end

function Storage.Execute(query, params)
    if not Storage.UsingMysql() then return nil end
    return MySQL.update.await(query, params or {})
end

function Storage.Insert(query, params)
    if not Storage.UsingMysql() then return nil end
    return MySQL.insert.await(query, params or {})
end

function Storage.InsertLater(query, params)
    if not Storage.UsingMysql() then return end
    MySQL.insert(query, params or {})
end


local oldColumns = {
    { 'banTable', 'banned_by', 'bannedby', "VARCHAR(64) NOT NULL DEFAULT ''" },
    { 'banTable', 'created_at', 'createdat', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'banTable', 'expires_at', 'expiresat', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'logTable', 'created_at', 'createdat', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'logTable', 'actor_name', 'actorname', "VARCHAR(64) NOT NULL DEFAULT ''" },
    { 'logTable', 'target_name', 'targetname', "VARCHAR(64) NOT NULL DEFAULT ''" },
    { 'watchlistTable', 'added_by', 'addedby', "VARCHAR(80) NOT NULL DEFAULT ''" },
    { 'watchlistTable', 'created_at', 'createdat', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'tagsTable', 'created_at', 'createdat', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'tagsTable', 'expires_at', 'expiresat', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'tagsTable', 'added_by', 'addedby', "VARCHAR(80) NOT NULL DEFAULT ''" },
    { 'relationshipsTable', 'related_identifier', 'relatedidentifier', 'VARCHAR(80) NOT NULL' },
    { 'relationshipsTable', 'related_name', 'relatedname', "VARCHAR(64) NOT NULL DEFAULT ''" },
    { 'relationshipsTable', 'created_at', 'createdat', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'relationshipsTable', 'added_by', 'addedby', "VARCHAR(80) NOT NULL DEFAULT ''" },
}

local function hasColumn(tableName, column)
    local count = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
    ]], { tableName, column })
    return (tonumber(count) or 0) > 0
end

local function renameOldColumns()
    for _, entry in ipairs(oldColumns) do
        local tableName = Config.Database[entry[1]]
        if tableName and hasColumn(tableName, entry[2]) and not hasColumn(tableName, entry[3]) then
            local sql = ('ALTER TABLE `%s` CHANGE `%s` `%s` %s'):format(tableName, entry[2], entry[3], entry[4])
            if pcall(MySQL.update.await, sql) then
                print(('%srenamed %s.%s to %s'):format(Config.ConsolePrefix, tableName, entry[2], entry[3]))
            else
                print(('%scould not rename %s.%s, run this by hand: %s;'):format(Config.ConsolePrefix, tableName, entry[2], sql))
            end
        end
    end
end

local function ensureSchema()
    if not useMysql then return end

    MySQL.update.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `identifiers` TEXT NULL,
            `name` VARCHAR(64) NOT NULL DEFAULT '',
            `reason` VARCHAR(255) NOT NULL DEFAULT '',
            `bannedby` VARCHAR(64) NOT NULL DEFAULT '',
            `createdat` INT UNSIGNED NOT NULL DEFAULT 0,
            `expiresat` INT UNSIGNED NOT NULL DEFAULT 0,
            `active` TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.banTable))

    MySQL.update.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `category` VARCHAR(32) NOT NULL,
            `createdat` INT UNSIGNED NOT NULL DEFAULT 0,
            `actor` VARCHAR(64) NOT NULL DEFAULT '',
            `actorname` VARCHAR(64) NOT NULL DEFAULT '',
            `target` VARCHAR(64) NOT NULL DEFAULT '',
            `targetname` VARCHAR(64) NOT NULL DEFAULT '',
            `message` TEXT NULL,
            `data` TEXT NULL,
            PRIMARY KEY (`id`),
            KEY `category` (`category`),
            KEY `actor` (`actor`),
            KEY `target` (`target`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.logTable))

    renameOldColumns()
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

    ready = true
end)
