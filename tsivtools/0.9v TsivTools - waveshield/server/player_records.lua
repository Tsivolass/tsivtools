TSIV.PlayerRecords = {}

local Records = TSIV.PlayerRecords
local Storage = TSIV.Storage
local Logs = TSIV.Logs
local Bans = TSIV.Bans

local units = { m = 60, h = 3600, d = 86400, w = 604800, [''] = 60 }

local function permitted(src, key)
    if src == 0 or TSIV.Can(src, key) then return true end
    TSIV.Notify(src, 'You dont have permission to do that !!', 'error')
    return false
end

local function actor(src)
    return src ~= 0 and TSIV.GetPrimaryIdentifier(src) or 'console'
end

local function actorName(src)
    return src ~= 0 and TSIV.GetName(src) or 'console'
end

local function duration(value)
    value = TSIV.SafeString(value, 24):lower()
    if value == '' or value == 'permanent' or value == 'perm' then return 0 end
    local amount, unit = value:match('^(%d+)%s*([mhdw]?)$')
    amount = tonumber(amount)
    if not amount then return nil end
    return amount * units[unit]
end

local function decodeIdentifiers(value)
    if type(value) ~= 'string' then return value or {} end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or {}
end

local function findWatch(identifier)
    if Storage.UsingMysql() then
        return Storage.Single(('SELECT * FROM `%s` WHERE identifier = ? AND active = 1 LIMIT 1')
            :format(Config.database.watchlistTable), { identifier })
    end
    for _, entry in ipairs(Storage.Get('watchlist')) do
        if entry.identifier == identifier and entry.active == 1 then return entry end
    end
end

function Records.AddWatch(target, note, by)
    local ids = TSIV.GetIdentifiers(target)
    local identifier = TSIV.GetPrimaryIdentifier(target)
    if findWatch(identifier) then return false end

    local entry = {
        identifier = identifier,
        identifiers = ids,
        name = TSIV.GetName(target),
        note = TSIV.SafeString(note, 200),
        added_by = by,
        created_at = os.time(),
        active = 1,
    }

    if Storage.UsingMysql() then
        Storage.Insert(([[
            INSERT INTO `%s` (identifier, identifiers, name, note, added_by, created_at, active)
            VALUES (?, ?, ?, ?, ?, ?, 1)
        ]]):format(Config.database.watchlistTable), {
            entry.identifier, json.encode(ids), entry.name, entry.note, entry.added_by, entry.created_at,
        })
    else
        local entries = Storage.Get('watchlist')
        entry.id = #entries + 1
        entries[#entries + 1] = entry
        Storage.MarkDirty('watchlist')
        Storage.Flush('watchlist')
    end

    Logs.Write({
        category = 'staff',
        message = ('Added %s to the watchlist'):format(TSIV.Describe(target)),
        actor = by,
        actorName = by,
        target = identifier,
        targetName = entry.name,
        data = { note = entry.note },
    })
    return true
end

function Records.RemoveWatch(identifier)
    if Storage.UsingMysql() then
        Storage.Execute(('UPDATE `%s` SET active = 0 WHERE identifier = ?')
            :format(Config.database.watchlistTable), { identifier })
        return
    end
    for _, entry in ipairs(Storage.Get('watchlist')) do
        if entry.identifier == identifier then entry.active = 0 end
    end
    Storage.MarkDirty('watchlist')
    Storage.Flush('watchlist')
end

function Records.Watchlist(onlineOnly)
    local rows
    if Storage.UsingMysql() then
        rows = Storage.Query(([[
            SELECT id, identifier, identifiers, name, note, added_by, created_at
            FROM `%s` WHERE active = 1 ORDER BY id DESC
        ]]):format(Config.database.watchlistTable)) or {}
    else
        rows = {}
        local entries = Storage.Get('watchlist')
        for index = #entries, 1, -1 do
            if entries[index].active == 1 then rows[#rows + 1] = entries[index] end
        end
    end

    local online = {}
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        online[TSIV.GetPrimaryIdentifier(id)] = id
    end

    local out = {}
    for _, row in ipairs(rows) do
        local id = online[row.identifier]
        if id or not onlineOnly then
            out[#out + 1] = {
                id = row.id,
                identifier = row.identifier,
                identifiers = decodeIdentifiers(row.identifiers),
                name = row.name,
                note = row.note,
                online = id,
            }
        end
    end
    return out
end

local function addTag(src, target, expires, content)
    local tag = {
        identifier = TSIV.GetPrimaryIdentifier(target),
        name = TSIV.GetName(target),
        content = content,
        created_at = os.time(),
        expires_at = expires,
        added_by = actor(src),
    }

    if Storage.UsingMysql() then
        local id = Storage.Insert(([[
            INSERT INTO `%s` (identifier, name, content, created_at, expires_at, added_by)
            VALUES (?, ?, ?, ?, ?, ?)
        ]]):format(Config.database.tagsTable), {
            tag.identifier, tag.name, tag.content, tag.created_at, tag.expires_at, tag.added_by,
        })
        if not id then return false end
    else
        local tags = Storage.Get('tags')
        tag.id = #tags + 1
        tags[#tags + 1] = tag
        Storage.MarkDirty('tags')
        Storage.Flush('tags')
    end

    Logs.Staff(src, ('Added player tag to %s'):format(TSIV.Describe(target)), target,
        { content = content, expires = expires })
    return true
end

local function tagPlayer(src, target, durationText, contentText)
    local seconds = duration(durationText)
    if not seconds then
        TSIV.Notify(src, 'Use a duration like 30m, 2h, 7d, or permanent.', 'error')
        return
    end

    local content = TSIV.SafeString(contentText, 160)
    if content == '' then
        TSIV.Notify(src, 'Tag content is required.', 'error')
        return
    end

    if addTag(src, target, seconds > 0 and os.time() + seconds or 0, content) then
        TSIV.Notify(src, 'Player tag added.', 'success')
    else
        TSIV.Notify(src, 'The player tag could not be stored. Check the server console.', 'error')
    end
end

local function playerRows(identifier, limit)
    if Storage.UsingMysql() then
        return Storage.Query(([[
            SELECT id, category, created_at AS at, actor, actor_name AS actorName,
                   target, target_name AS targetName, message, data
            FROM `%s` WHERE actor = ? OR target = ?
            ORDER BY id DESC LIMIT %d
        ]]):format(Config.database.logTable, limit), { identifier, identifier }) or {}
    end

    local out = {}
    local logs = Storage.Get('logs')
    for index = #logs, 1, -1 do
        local row = logs[index]
        if row.target == identifier or row.actor == identifier then
            out[#out + 1] = row
            if #out >= limit then break end
        end
    end
    return out
end

local function playerTags(identifier)
    if Storage.UsingMysql() then
        return Storage.Query(([[
            SELECT content, created_at AS at, expires_at, added_by FROM `%s`
            WHERE identifier = ? AND (expires_at = 0 OR expires_at > ?) ORDER BY id DESC
        ]]):format(Config.database.tagsTable), { identifier, os.time() }) or {}
    end

    local out = {}
    local now = os.time()
    for _, tag in ipairs(Storage.Get('tags')) do
        if tag.identifier == identifier and (tag.expires_at == 0 or tag.expires_at > now) then
            out[#out + 1] = tag
        end
    end
    return out
end

local function relationshipsOf(identifier)
    if Storage.UsingMysql() then
        return Storage.Query(([[
            SELECT identifier, related_identifier, related_name, note FROM `%s`
            WHERE identifier = ? OR related_identifier = ?
        ]]):format(Config.database.relationshipsTable), { identifier, identifier }) or {}
    end

    local out = {}
    for _, row in ipairs(Storage.Get('relationships')) do
        if row.identifier == identifier or row.related_identifier == identifier then
            out[#out + 1] = row
        end
    end
    return out
end

local function ratingLines(identifier, target)
    local lines = {}
    if target then lines[#lines + 1] = ('player    : %s'):format(TSIV.Describe(target)) end
    lines[#lines + 1] = ('identifier: %s'):format(identifier)

    local tags = playerTags(identifier)
    lines[#lines + 1] = ('tags      : %d active'):format(#tags)
    for _, tag in ipairs(tags) do
        lines[#lines + 1] = ('  %s%s'):format(tag.content, tag.expires_at > 0
            and (' (until %s)'):format(TSIV.FormatTimestamp(tag.expires_at)) or ' (permanent)')
    end

    local links = relationshipsOf(identifier)
    lines[#lines + 1] = ('linked    : %d player(s)'):format(#links)
    for _, row in ipairs(links) do
        local other = row.identifier == identifier
            and (row.related_name ~= '' and row.related_name or row.related_identifier)
            or row.identifier
        lines[#lines + 1] = ('  %s%s'):format(other, row.note ~= '' and (' - ' .. row.note) or '')
    end

    local bans = Bans.History(identifier)
    lines[#lines + 1] = ('bans      : %d on record'):format(#bans)
    for _, ban in ipairs(bans) do
        lines[#lines + 1] = ('  #%s %s - %s (%s)'):format(ban.id, TSIV.FormatTimestamp(ban.created_at),
            ban.reason, Bans.IsActive(ban) and 'active' or 'lifted or expired')
    end

    local rows = playerRows(identifier, 100)
    lines[#lines + 1] = ('records   : %d'):format(#rows)
    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('  [%s] %s: %s'):format(TSIV.FormatTimestamp(row.at), row.category, row.message or '')
    end

    return lines
end

TSIV.RegisterRequest('watchlist.list', 'player.watchlist', function(_, payload)
    return Records.Watchlist(payload.online == true)
end)

TSIV.RegisterAction('watchlist.add', 'player.watchlist', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'Player isnt online !', 'error')
        return
    end
    if Records.AddWatch(target, payload.note, TSIV.GetName(src)) then
        TSIV.Notify(src, ('Added %s to the watchlist'):format(TSIV.GetName(target)), 'success')
    else
        TSIV.Notify(src, 'That player is already on the watchlist.', 'error')
    end
end)

TSIV.RegisterAction('watchlist.remove', 'player.watchlist', function(src, payload)
    local identifier = TSIV.SafeString(payload.identifier, 80)
    if identifier == '' then return end
    Records.RemoveWatch(identifier)
    TSIV.Notify(src, 'Removed from watchlist.', 'success')
    Logs.Staff(src, ('Removed %s from the watchlist'):format(identifier), identifier)
end)

TSIV.RegisterAction('watchlist.ban', 'player.ban', function(src, payload)
    local identifiers = {}
    if type(payload.identifiers) == 'table' then
        for _, identifier in pairs(payload.identifiers) do
            if type(identifier) == 'string' then
                identifiers[#identifiers + 1] = TSIV.SafeString(identifier, 80)
            end
        end
    end
    if #identifiers == 0 then
        TSIV.Notify(src, 'No stored identifiers are available for that player.', 'error')
        return
    end

    local reason = TSIV.SafeString(payload.reason, 200)
    if reason == '' then reason = 'No reason given' end

    local ban = Bans.Add(identifiers, TSIV.SafeString(payload.name, 48), reason, 0, TSIV.GetName(src))
    if ban then
        TSIV.Notify(src, ('Offline ban created (#%d).'):format(ban.id), 'success')
    else
        TSIV.Notify(src, 'The ban could not be stored !!', 'error')
    end
end)

TSIV.RegisterAction('player.tag', 'player.tags', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'Player isnt online !', 'error')
        return
    end
    tagPlayer(src, target, payload.duration, payload.content)
end)

TSIV.RegisterRequest('player.rating', 'player.rating', function(_, payload)
    local target = TSIV.ResolveTarget(payload.target)
    local identifier = target and TSIV.GetPrimaryIdentifier(target) or TSIV.SafeString(payload.identifier, 80)
    if identifier == '' then
        return { title = 'Player rating', lines = { 'A player ID or identifier is required.' } }
    end
    return { title = 'Player rating', lines = ratingLines(identifier, target) }
end)

RegisterCommand('rating', function(src, args)
    if not permitted(src, 'player.rating') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target then
        TSIV.Notify(src, 'usage: /rating <server id>', 'error')
        return
    end
    TSIV.ConsoleBlock(src, 'Player rating', ratingLines(TSIV.GetPrimaryIdentifier(target), target))
end, false)

RegisterCommand('watchlist', function(src, args)
    if not permitted(src, 'player.watchlist') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target then
        TSIV.Notify(src, 'usage: /watchlist <server id> [note]', 'error')
        return
    end
    if Records.AddWatch(target, table.concat(args, ' ', 2), actorName(src)) then
        TSIV.Notify(src, ('Added %s to the watchlist'):format(TSIV.GetName(target)), 'success')
    else
        TSIV.Notify(src, 'That player is already on the watchlist.', 'error')
    end
end, false)

RegisterCommand('player_tag', function(src, args)
    if not permitted(src, 'player.tags') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target or not args[2] then
        TSIV.Notify(src, 'usage: /player_tag <id> <duration|permanent> <content>', 'error')
        return
    end
    tagPlayer(src, target, args[2], table.concat(args, ' ', 3))
end, false)

AddEventHandler('playerJoining', function()
    local src = source
    local ids = TSIV.GetIdentifiers(src)
    local identifier = TSIV.GetPrimaryIdentifier(src)
    local name = TSIV.GetName(src)
    local steam = ids.steam or ''

    if findWatch(identifier) then
        TSIV.StaffBroadcast('superadmin', ('Watchlist login: %s joined (server ID %d)'):format(name, src))
        for _, member in ipairs(TSIV.GetStaff('superadmin')) do
            TriggerClientEvent(TSIV.Events.watchlist, member.source, name, src)
        end
    end

    if Storage.UsingMysql() then
        local seen = Storage.Single(('SELECT id FROM `%s` WHERE license = ? AND steam = ? AND name = ? LIMIT 1')
            :format(Config.database.aliasesTable), { identifier, steam, name })
        if not seen then
            Storage.Insert(('INSERT INTO `%s` (license, steam, name, at) VALUES (?, ?, ?, ?)')
                :format(Config.database.aliasesTable), { identifier, steam, name, os.time() })
        end
        return
    end

    local aliases = Storage.Get('aliases')
    for _, row in ipairs(aliases) do
        if row.license == identifier and row.name == name and row.steam == steam then return end
    end
    aliases[#aliases + 1] = { license = identifier, steam = steam, name = name, at = os.time() }
    Storage.MarkDirty('aliases')
end)

TSIV.RegisterRequest('player.aliases', 'player.aliases', function(_, payload)
    local target = TSIV.ResolveTarget(payload.target)
    local license = target and TSIV.GetPrimaryIdentifier(target) or TSIV.SafeString(payload.license, 80)
    if license == '' then return { title = 'Player aliases', lines = { 'A player ID is required.' } } end

    local rows
    if Storage.UsingMysql() then
        rows = Storage.Query(('SELECT steam, name, at FROM `%s` WHERE license = ? ORDER BY id DESC')
            :format(Config.database.aliasesTable), { license }) or {}
    else
        rows = {}
        for _, row in ipairs(Storage.Get('aliases')) do
            if row.license == license then rows[#rows + 1] = row end
        end
    end

    local lines = { 'license: ' .. license }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('[%s] %s / %s'):format(TSIV.FormatTimestamp(row.at), row.name,
            row.steam ~= '' and row.steam or 'no steam')
    end
    if #rows == 0 then lines[#lines + 1] = 'No aliases recorded yet.' end
    return { title = 'Player aliases', lines = lines }
end)

TSIV.RegisterAction('player.link', 'player.relationships', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    local related = TSIV.ResolveTarget(payload.related)
    if not target or not related or target == related then
        TSIV.Notify(src, 'Enter two different online player IDs.', 'error')
        return
    end

    local row = {
        identifier = TSIV.GetPrimaryIdentifier(target),
        related_identifier = TSIV.GetPrimaryIdentifier(related),
        related_name = TSIV.GetName(related),
        note = TSIV.SafeString(payload.note, 160),
        created_at = os.time(),
        added_by = actor(src),
    }

    if Storage.UsingMysql() then
        Storage.Insert(([[
            INSERT INTO `%s` (identifier, related_identifier, related_name, note, created_at, added_by)
            VALUES (?, ?, ?, ?, ?, ?)
        ]]):format(Config.database.relationshipsTable), {
            row.identifier, row.related_identifier, row.related_name, row.note, row.created_at, row.added_by,
        })
    else
        local rows = Storage.Get('relationships')
        rows[#rows + 1] = row
        Storage.MarkDirty('relationships')
        Storage.Flush('relationships')
    end

    Logs.Staff(src, ('Linked %s with %s'):format(TSIV.Describe(target), TSIV.Describe(related)), target)
    TSIV.Notify(src, 'Players linked.', 'success')
end)
