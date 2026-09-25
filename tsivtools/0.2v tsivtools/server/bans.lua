tsivtools.Bans = {}

local Bans = tsivtools.Bans
local Storage = tsivtools.Storage
local nextId = 1

CreateThread(function()
    Storage.WaitReady()
    if Storage.UsingMysql() then return end
    for _, ban in ipairs(Storage.Get('bans')) do
        if ban.id and ban.id >= nextId then nextId = ban.id + 1 end
    end
end)

local function isExpired(ban)
    local expires = tonumber(ban.expiresat) or 0
    return expires > 0 and expires <= os.time()
end

function Bans.IsActive(ban)
    return ban.active == 1 and not isExpired(ban)
end

local function expiryText(ban)
    local expires = tonumber(ban.expiresat) or 0
    return expires > 0 and tsivtools.FormatTimestamp(expires) or Config.Bans.permanentText
end

function Bans.Add(identifiers, name, reason, minutes, bannedBy)
    if type(identifiers) == 'string' then identifiers = { identifiers } end
    if not identifiers or #identifiers == 0 then return nil end

    minutes = tonumber(minutes) or 0
    reason = tsivtools.SafeString(reason, 200)
    if reason == '' then reason = 'No reason given' end

    local ban = {
        id = nextId,
        identifier = identifiers[1],
        identifiers = identifiers,
        name = tsivtools.SafeString(name, 48),
        reason = reason,
        bannedby = tsivtools.SafeString(bannedBy or 'TsivTools', 48),
        createdat = os.time(),
        expiresat = minutes > 0 and os.time() + math.floor(minutes * 60) or 0,
        active = 1,
    }
    nextId = nextId + 1

    if Storage.UsingMysql() then
        local id = Storage.Insert(([[
            INSERT INTO `%s` (identifier, identifiers, name, reason, bannedby, createdat, expiresat, active)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1)
        ]]):format(Config.Database.banTable), {
            ban.identifier, json.encode(ban.identifiers), ban.name, ban.reason,
            ban.bannedby, ban.createdat, ban.expiresat,
        })
        if not id then return nil end
        ban.id = id
    else
        local store = Storage.Get('bans')
        store[#store + 1] = ban
        Storage.MarkDirty('bans')
        Storage.Flush('bans')
    end

    tsivtools.Logs.Write({
        category = 'ban',
        message = ('Banned %s for %s - %s'):format(
            ban.name ~= '' and ban.name or ban.identifier, tsivtools.FormatDuration(minutes), ban.reason),
        actor = ban.bannedby,
        actorName = ban.bannedby,
        target = ban.identifier,
        targetName = ban.name,
        data = { banId = ban.id, expires = ban.expiresat, identifiers = ban.identifiers },
    })

    return ban
end

local function banRows(identifiers, activeOnly)
    local clauses, params = {}, {}
    for _, identifier in ipairs(identifiers) do
        clauses[#clauses + 1] = 'identifier = ? OR identifiers LIKE ?'
        params[#params + 1] = identifier
        params[#params + 1] = '%"' .. identifier .. '"%'
    end
    if #clauses == 0 then return {} end

    return Storage.Query(('SELECT * FROM `%s` WHERE %s(%s) ORDER BY id DESC'):format(
        Config.Database.banTable, activeOnly and 'active = 1 AND ' or '', table.concat(clauses, ' OR ')), params) or {}
end

local function matches(ban, lookup)
    for _, stored in ipairs(ban.identifiers or { ban.identifier }) do
        if lookup[stored] then return true end
    end
    return lookup[ban.identifier] == true
end

function Bans.Find(identifiers)
    if Storage.UsingMysql() then
        for _, row in ipairs(banRows(identifiers, true)) do
            if isExpired(row) then
                Bans.Remove(row.id)
            else
                return row
            end
        end
        return nil
    end

    local lookup = {}
    for _, identifier in ipairs(identifiers) do lookup[identifier] = true end

    for _, ban in ipairs(Storage.Get('bans')) do
        if ban.active == 1 and matches(ban, lookup) then
            if isExpired(ban) then
                ban.active = 0
                Storage.MarkDirty('bans')
            else
                return ban
            end
        end
    end
    return nil
end

function Bans.History(identifier)
    if Storage.UsingMysql() then
        return banRows({ identifier }, false)
    end

    local lookup = { [identifier] = true }
    local out = {}
    local store = Storage.Get('bans')
    for index = #store, 1, -1 do
        if matches(store[index], lookup) then out[#out + 1] = store[index] end
    end
    return out
end

function Bans.Remove(banId)
    banId = tonumber(banId)
    if not banId then return nil end

    if Storage.UsingMysql() then
        local row = Storage.Single(('SELECT * FROM `%s` WHERE id = ?'):format(Config.Database.banTable), { banId })
        if not row then return nil end
        Storage.Execute(('UPDATE `%s` SET active = 0 WHERE id = ?'):format(Config.Database.banTable), { banId })
        return row
    end

    for _, ban in ipairs(Storage.Get('bans')) do
        if ban.id == banId and ban.active == 1 then
            ban.active = 0
            Storage.MarkDirty('bans')
            Storage.Flush('bans')
            return ban
        end
    end
    return nil
end

function Bans.List(query, limit)
    query = tsivtools.SafeString(query, 64):lower()
    limit = math.min(limit or 30, 100)
    local out = {}

    local function wanted(ban)
        if not Bans.IsActive(ban) then return false end
        if query == '' then return true end
        return ban.identifier:lower():find(query, 1, true) ~= nil
            or ban.name:lower():find(query, 1, true) ~= nil
    end

    local rows
    if Storage.UsingMysql() then
        rows = Storage.Query(('SELECT * FROM `%s` WHERE active = 1 ORDER BY id DESC LIMIT 200')
            :format(Config.Database.banTable)) or {}
    else
        rows = {}
        local store = Storage.Get('bans')
        for index = #store, 1, -1 do rows[#rows + 1] = store[index] end
    end

    for _, ban in ipairs(rows) do
        if wanted(ban) then
            out[#out + 1] = ban
            if #out >= limit then break end
        end
    end
    return out
end

function Bans.BanPlayer(target, reason, minutes, bannedBy)
    local identifiers = {}
    for _, identifier in pairs(tsivtools.GetIdentifiers(target)) do
        identifiers[#identifiers + 1] = identifier
    end

    local ban = Bans.Add(identifiers, tsivtools.GetName(target), reason, minutes, bannedBy)
    if not ban then
        DropPlayer(target, Config.Bans.message:format(tsivtools.SafeString(reason, 200), Config.Bans.permanentText, '?'))
        return nil
    end

    local function drop()
        DropPlayer(target, Config.Bans.message:format(ban.reason, expiryText(ban), tostring(ban.id)))
    end

    if tsivtools.Clips then
        tsivtools.Clips.Before(target, ban.reason, drop)
    else
        drop()
    end

    return ban
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local identifiers = {}
    for _, kind in ipairs(Config.Bans.identifierTypes) do
        local identifier = GetPlayerIdentifierByType(src, kind)
        if identifier then identifiers[#identifiers + 1] = identifier end
    end

    local ok, ban = pcall(Bans.Find, identifiers)
    if not ok then
        print(('%sthe ban check failed for %s, letting them in: %s'):format(Config.ConsolePrefix, name, tostring(ban)))
        deferrals.done()
        return
    end

    if ban then
        deferrals.done(Config.Bans.message:format(ban.reason, expiryText(ban), tostring(ban.id)))
        print(('%srefused a banned connection: %s (ban %s)'):format(Config.ConsolePrefix, ban.identifier, tostring(ban.id)))
        return
    end

    deferrals.done()
end)

tsivtools.RegisterAction('player.ban', 'player.ban', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'That player isnt online !', 'error')
        return
    end

    local minutes = tsivtools.ToInt(payload.minutes, 0, 60 * 24 * 3650) or 0
    local targetName = tsivtools.GetName(target)
    local ban = Bans.BanPlayer(target, payload.reason, minutes, tsivtools.GetName(src))
    if not ban then
        tsivtools.Notify(src, 'The ban could not be stored !!', 'error')
        return
    end

    tsivtools.Notify(src, ('Banned %s (%s) - ban ID %s'):format(targetName, tsivtools.FormatDuration(minutes), ban.id), 'success')
    tsivtools.Logs.Staff(src, ('Banned %s for %s - %s'):format(targetName, tsivtools.FormatDuration(minutes), ban.reason), ban.identifier)
    tsivtools.StaffBroadcast('mod', ('%s%s banned %s (%s)'):format(Config.Prefix, tsivtools.GetName(src), targetName, tsivtools.FormatDuration(minutes)))
end)

tsivtools.RegisterAction('player.unban', 'player.unban', function(src, payload)
    local ban = Bans.Remove(payload.banId)
    if not ban then
        tsivtools.Notify(src, 'No active ban with that ID !', 'error')
        return
    end
    tsivtools.Notify(src, ('removed ban %s (%s)'):format(ban.id, ban.name ~= '' and ban.name or ban.identifier), 'success')
    tsivtools.Logs.Staff(src, ('removed ban %s on %s'):format(ban.id, ban.identifier), ban.identifier)
end)

tsivtools.RegisterRequest('bans.list', 'player.unban', function(_, payload)
    local out = {}
    for _, ban in ipairs(Bans.List(payload.query, 40)) do
        out[#out + 1] = {
            id = ban.id,
            name = ban.name,
            identifier = ban.identifier,
            reason = ban.reason,
            bannedBy = ban.bannedby,
            expires = ban.expiresat,
            expiresText = expiryText(ban),
        }
    end
    return out
end)
