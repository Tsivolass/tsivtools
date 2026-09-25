tsivtools.Bans = {}

local Bans = tsivtools.Bans
local nextId = 1

local function fileStore()
    return tsivtools.Storage.Get('bans')
end

CreateThread(function()
    tsivtools.Storage.WaitReady()
    if not tsivtools.Storage.UsingMysql() then
        for _, ban in ipairs(fileStore()) do
            if ban.id and ban.id >= nextId then nextId = ban.id + 1 end
        end
    end
end)

local function isExpired(ban)
    return ban.expiresat and ban.expiresat > 0 and ban.expiresat <= os.time()
end

function Bans.Add(identifiers, name, reason, minutes, bannedBy)
    if type(identifiers) == 'string' then identifiers = { identifiers } end
    if not identifiers or #identifiers == 0 then return nil end

    reason = tsivtools.SafeString(reason, 200)
    if reason == '' then reason = 'No reason given' end

    local expires = 0
    minutes = tonumber(minutes) or 0
    if minutes > 0 then
        expires = os.time() + math.floor(minutes * 60)
    end

    local ban = {
        id = nextId,
        identifier = identifiers[1],
        identifiers = identifiers,
        name = tsivtools.SafeString(name or '', 48),
        reason = reason,
        bannedby = tsivtools.SafeString(bannedBy or 'tsivtools', 48),
        createdat = os.time(),
        expiresat = expires,
        active = 1,
    }
    nextId = nextId + 1

    if tsivtools.Storage.UsingMysql() then
        local id = tsivtools.Storage.Insert(([[
            INSERT INTO `%s` (identifier, identifiers, name, reason, bannedby, createdat, expiresat, active)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1)
        ]]):format(Config.Database.banTable), {
            ban.identifier, json.encode(ban.identifiers), ban.name, ban.reason,
            ban.bannedby, ban.createdat, ban.expiresat,
        })
        if not id then return nil end
        ban.id = id
    else
        local store = fileStore()
        store[#store + 1] = ban
        tsivtools.Storage.MarkDirty('bans')
        tsivtools.Storage.Flush('bans')
    end

    tsivtools.Logs.Write({
        category = 'ban',
        message = ('Banned %s for %s - %s'):format(
            ban.name ~= '' and ban.name or ban.identifier,
            tsivtools.FormatDuration(minutes), ban.reason),
        actor = bannedBy or 'tsivtools',
        actorName = bannedBy or 'tsivtools',
        target = ban.identifier,
        targetName = ban.name,
        data = { banId = ban.id, expires = ban.expiresat, identifiers = ban.identifiers },
    })

    return ban
end

local function matches(ban, lookup)
    for _, stored in ipairs(ban.identifiers or { ban.identifier }) do
        if lookup[stored] then return true end
    end
    return lookup[ban.identifier] == true
end

function Bans.Find(identifiers)
    if tsivtools.Storage.UsingMysql() then
        local clauses, params = {}, {}
        for _, identifier in ipairs(identifiers) do
            clauses[#clauses + 1] = 'identifier = ? OR identifiers LIKE ?'
            params[#params + 1] = identifier
            params[#params + 1] = '%"' .. identifier .. '"%'
        end
        if #clauses == 0 then return nil end

        local rows = tsivtools.Storage.Query(('SELECT * FROM `%s` WHERE active = 1 AND (%s) ORDER BY id DESC')
            :format(Config.Database.banTable, table.concat(clauses, ' OR ')), params) or {}
        for _, row in ipairs(rows) do
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

    for _, ban in ipairs(fileStore()) do
        if ban.active == 1 and matches(ban, lookup) then
            if isExpired(ban) then
                ban.active = 0
                tsivtools.Storage.MarkDirty('bans')
            else
                return ban
            end
        end
    end
    return nil
end

function Bans.Remove(banId)
    banId = tonumber(banId)
    if not banId then return nil end

    if tsivtools.Storage.UsingMysql() then
        local row = tsivtools.Storage.Single(([[SELECT * FROM `%s` WHERE id = ?]]):format(Config.Database.banTable), { banId })
        if not row then return nil end
        tsivtools.Storage.Execute(([[UPDATE `%s` SET active = 0 WHERE id = ?]]):format(Config.Database.banTable), { banId })
        return row
    end

    for _, ban in ipairs(fileStore()) do
        if ban.id == banId and ban.active == 1 then
            ban.active = 0
            tsivtools.Storage.MarkDirty('bans')
            tsivtools.Storage.Flush('bans')
            return ban
        end
    end
    return nil
end

function Bans.List(query, limit)
    query = (query or ''):lower()
    limit = math.min(limit or 30, 100)
    local out = {}

    local function matches(ban)
        if query == '' then return true end
        if (ban.identifier or ''):lower():find(query, 1, true) then return true end
        if (ban.name or ''):lower():find(query, 1, true) then return true end
        return false
    end

    if tsivtools.Storage.UsingMysql() then
        local rows = tsivtools.Storage.Query(([[
            SELECT * FROM `%s` WHERE active = 1 ORDER BY id DESC LIMIT 200
        ]]):format(Config.Database.banTable)) or {}
        for _, ban in ipairs(rows) do
            if not isExpired(ban) and matches(ban) then
                out[#out + 1] = ban
                if #out >= limit then break end
            end
        end
    else
        local store = fileStore()
        for index = #store, 1, -1 do
            local ban = store[index]
            if ban.active == 1 and not isExpired(ban) and matches(ban) then
                out[#out + 1] = ban
                if #out >= limit then break end
            end
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

    DropPlayer(target, Config.Bans.message:format(
        ban.reason,
        ban.expiresat > 0 and tsivtools.FormatTimestamp(ban.expiresat) or Config.Bans.permanentText,
        tostring(ban.id)))

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
        local expiry = (ban.expiresat and ban.expiresat > 0)
            and tsivtools.FormatTimestamp(ban.expiresat) or Config.Bans.permanentText
        deferrals.done(Config.Bans.message:format(ban.reason, expiry, tostring(ban.id)))
        print(('%srefused a banned connection: %s (ban %s)'):format(
            Config.ConsolePrefix, ban.identifier, tostring(ban.id)))
        return
    end

    deferrals.done()
end)

tsivtools.RegisterAction('player.ban', 'player.ban', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'That player is not online.', 'error')
        return
    end
    if not tsivtools.OutranksTarget(src, target) then
        tsivtools.Notify(src, 'You cannot ban somebody of your own rank or higher.', 'error')
        return
    end

    local minutes = tsivtools.ToInt(payload.minutes, 0, 60 * 24 * 3650) or 0
    local reason = tsivtools.SafeString(payload.reason, 200)
    if reason == '' then reason = 'No reason given' end

    local targetName = tsivtools.GetName(target)
    local ban = Bans.BanPlayer(target, reason, minutes, tsivtools.GetName(src))
    if not ban then
        tsivtools.Notify(src, 'The ban could not be stored.', 'error')
        return
    end

    tsivtools.Notify(src, ('Banned %s (%s) - ban ID %s'):format(targetName, tsivtools.FormatDuration(minutes), ban.id), 'success')
    tsivtools.Logs.Staff(src, ('Banned %s for %s - %s'):format(targetName, tsivtools.FormatDuration(minutes), reason), ban.identifier)
    tsivtools.StaffBroadcast('mod', ('%s%s banned %s (%s)'):format(Config.Prefix, tsivtools.GetName(src), targetName, tsivtools.FormatDuration(minutes)))
end)

tsivtools.RegisterAction('player.unban', 'player.unban', function(src, payload)
    local ban = Bans.Remove(payload.banId)
    if not ban then
        tsivtools.Notify(src, 'No active ban with that ID.', 'error')
        return
    end
    tsivtools.Notify(src, ('Lifted ban %s (%s)'):format(ban.id, ban.name ~= '' and ban.name or ban.identifier), 'success')
    tsivtools.Logs.Staff(src, ('Lifted ban %s on %s'):format(ban.id, ban.identifier), ban.identifier)
end)

tsivtools.RegisterRequest('bans.list', 'player.unban', function(src, payload)
    local query = tsivtools.SafeString(payload.query, 64)
    local bans = Bans.List(query, 40)
    local out = {}
    for _, ban in ipairs(bans) do
        out[#out + 1] = {
            id = ban.id,
            name = ban.name,
            identifier = ban.identifier,
            reason = ban.reason,
            bannedBy = ban.bannedby,
            expires = ban.expiresat,
            expiresText = (ban.expiresat and ban.expiresat > 0)
                and tsivtools.FormatTimestamp(ban.expiresat) or Config.Bans.permanentText,
        }
    end
    return out
end)
