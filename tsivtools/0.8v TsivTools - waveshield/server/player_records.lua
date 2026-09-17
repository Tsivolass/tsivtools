TSIV.PlayerRecords = {}
local Records = TSIV.PlayerRecords
local function permitted(src, key)
    if src == 0 or TSIV.Can(src, key) then return true end
    TSIV.Notify(src, 'You dont have permission to do that !!', 'error')
    return false
end

local function store(name)
    return TSIV.Storage.Get(name)
end

local function actor(src)
    return src ~= 0 and TSIV.GetPrimaryIdentifier(src) or 'console'
end

local function playerData(src)
    local ids = TSIV.GetIdentifiers(src)
    return ids.license or TSIV.GetPrimaryIdentifier(src), ids, TSIV.GetName(src)
end

local function duration(value)
    value = TSIV.SafeString(value, 24):lower()
    if value == '' or value == 'permanent' or value == 'perm' then return 0 end
    local amount, unit = value:match('^(%d+)%s*([mhdw]?)$')
    amount = tonumber(amount)
    if not amount then return nil end
    return amount * ({ m = 60, h = 3600, d = 86400, w = 604800, [''] = 60 })[unit]
end

local function findWatch(identifier)
    if TSIV.Storage.UsingMysql() then
        return TSIV.Storage.Single(([[
            SELECT * FROM `%s` WHERE identifier = ? AND active = 1 LIMIT 1
        ]]):format(Config.database.watchlistTable), { identifier })
    end
    for _, entry in ipairs(store('watchlist')) do
        if entry.identifier == identifier and entry.active == 1 then return entry end
    end
end

function Records.AddWatch(src, note, by)
    local identifier, ids, name = playerData(src)
    local entry = {
        identifier = identifier, identifiers = ids, name = name,
        note = TSIV.SafeString(note or '', 200), added_by = by or 'TsivTools',
        created_at = os.time(), active = 1,
    }
    if findWatch(identifier) then return false end
    if TSIV.Storage.UsingMysql() then
        TSIV.Storage.Insert(([[
            INSERT INTO `%s` (identifier, identifiers, name, note, added_by, created_at, active)
            VALUES (?, ?, ?, ?, ?, ?, 1)
        ]]):format(Config.database.watchlistTable), {
            identifier, json.encode(ids), name, entry.note, entry.added_by, entry.created_at,
        })
    else
        local entries = store('watchlist')
        entry.id = #entries + 1
        entries[#entries + 1] = entry
        TSIV.Storage.MarkDirty('watchlist')
        TSIV.Storage.Flush('watchlist')
    end
    Logs.Write({
        category = 'staff',
        message = ('Added %s to the watchlist'):format(TSIV.Describe(src)),
        actor = by or 'TsivTools', actorName = by or 'TsivTools',
        target = identifier, targetName = name, data = { note = entry.note },
    })
    return true
end

function Records.RemoveWatch(entry)
    if TSIV.Storage.UsingMysql() then
        TSIV.Storage.Execute(([[
            UPDATE `%s` SET active = 0 WHERE identifier = ?
        ]]):format(Config.database.watchlistTable), { entry.identifier })
        return
    end
    for _, item in ipairs(store('watchlist')) do
        if item.identifier == entry.identifier then item.active = 0 end
    end
    TSIV.Storage.MarkDirty('watchlist')
    TSIV.Storage.Flush('watchlist')
end

function Records.Watchlist(onlineOnly)
    local out = {}
    if TSIV.Storage.UsingMysql() then
        out = TSIV.Storage.Query(([[
            SELECT id, identifier, identifiers, name, note, added_by, created_at
            FROM `%s` WHERE active = 1 ORDER BY id DESC
        ]]):format(Config.database.watchlistTable)) or {}
    else
        for _, entry in ipairs(store('watchlist')) do
            if entry.active == 1 then out[#out + 1] = entry end
        end
    end
    for _, entry in ipairs(out) do
        local online
        for _, id in ipairs(GetPlayers()) do
            id = tonumber(id)
            if TSIV.GetPrimaryIdentifier(id) == entry.identifier then online = id break end
        end
        entry.online = online
        if onlineOnly and not online then entry._skip = true end
        if type(entry.identifiers) == 'string' then
            local ok, decoded = pcall(json.decode, entry.identifiers)
            entry.identifiers = ok and decoded or {}
        end
    end
    local filtered = {}
    for _, entry in ipairs(out) do if not entry._skip then filtered[#filtered + 1] = entry end end
    return filtered
end

local function addTag(src, target, expires, content)
    local identifier = TSIV.GetPrimaryIdentifier(target)
    local tag = { identifier = identifier, name = TSIV.GetName(target), content = content,
        created_at = os.time(), expires_at = expires, added_by = actor(src) }
    if TSIV.Storage.UsingMysql() then
        local id = TSIV.Storage.Insert(([[
            INSERT INTO `%s` (identifier, name, content, created_at, expires_at, added_by)
            VALUES (?, ?, ?, ?, ?, ?)
        ]]):format(Config.database.tagsTable), {
            tag.identifier, tag.name, tag.content, tag.created_at, tag.expires_at, tag.added_by,
        })
        if not id then return false end
    else
        local tags = store('tags'); tag.id = #tags + 1; tags[#tags + 1] = tag
        TSIV.Storage.MarkDirty('tags'); TSIV.Storage.Flush('tags')
    end
    Logs.Staff(src, ('Added player tag to %s'):format(TSIV.Describe(target)), target, { content = content, expires = expires })
    return true
end

local function playerRows(identifier, limit)
    if TSIV.Storage.UsingMysql() then
        return TSIV.Storage.Query(([[
            SELECT id, category, created_at AS at, actor, actor_name AS actorName,
                   target, target_name AS targetName, message, data
            FROM `%s` WHERE actor = ? OR target = ?
            ORDER BY id DESC LIMIT %d
        ]]):format(Config.database.logTable, limit or 100), { identifier, identifier }) or {}
    end
    local out = {}
    for i = #store('logs'), 1, -1 do
        local row = store('logs')[i]
        if row.target == identifier or row.actor == identifier then out[#out + 1] = row end
        if #out >= (limit or 100) then break end
    end
    return out
end

local function playerTags(identifier)
    if TSIV.Storage.UsingMysql() then
        local query = 'SELECT content, created_at AS at, expires_at, added_by '
            .. 'FROM `%s` WHERE identifier = ? AND (expires_at = 0 OR expires_at > ?) '
            .. 'ORDER BY id DESC'
        return TSIV.Storage.Query(query:format(Config.database.tagsTable), { identifier, os.time() }) or {}
    end

    local out = {}
    for _, tag in ipairs(store('tags')) do
        if tag.identifier == identifier and (tag.expires_at == 0 or tag.expires_at > os.time()) then
            out[#out + 1] = tag
        end
    end
    return out
end

TSIV.RegisterRequest('watchlist.list', 'player.watchlist', function(_, payload)
    return Records.Watchlist(payload.online == true)
end)

TSIV.RegisterAction('watchlist.add', 'player.watchlist', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then TSIV.Notify(src, 'Player isnt online !', 'error'); return end
    if Records.AddWatch(target, payload.note, TSIV.GetName(src)) then
        TSIV.Notify(src, ('Added %s to the watchlist'):format(TSIV.GetName(target)), 'success')
    else TSIV.Notify(src, 'That player is already on the watchlist.', 'error') end
end)

TSIV.RegisterAction('watchlist.remove', 'player.watchlist', function(src, payload)
    local entry = payload.identifier and { identifier = payload.identifier } or nil
    if entry then Records.RemoveWatch(entry); TSIV.Notify(src, 'Removed from watchlist.', 'success') end
end)

TSIV.RegisterAction('watchlist.ban', 'player.ban', function(src, payload)
    local identifiers = {}
    if type(payload.identifiers) == 'table' then
        for _, identifier in pairs(payload.identifiers) do identifiers[#identifiers + 1] = identifier end
    end
    if #identifiers == 0 then
        TSIV.Notify(src, 'No stored identifiers are available for that player.', 'error'); return
    end
    local ban = Bans.Add(identifiers, payload.name or '', TSIV.SafeString(payload.reason, 200), 0, TSIV.GetName(src))
    if ban then TSIV.Notify(src, ('Global database ban created (#%d).'):format(ban.id), 'success') end
end)

TSIV.RegisterAction('player.tag', 'player.tags', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then TSIV.Notify(src, 'Player isnt online !', 'error'); return end
    local seconds = duration(payload.duration)
    if seconds == nil then TSIV.Notify(src, 'Use a duration like 30m, 2h, 7d, or permanent.', 'error'); return end
    local content = TSIV.SafeString(payload.content, 160)
    if content == '' then TSIV.Notify(src, 'Tag content is required.', 'error'); return end
    if addTag(src, target, seconds > 0 and os.time() + seconds or 0, content) then
        TSIV.Notify(src, 'Player tag added.', 'success')
    else
        TSIV.Notify(src, 'The player tag could not be stored. Check the server console.', 'error')
    end
end)

TSIV.RegisterRequest('player.rating', 'player.rating', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    local identifier = target and TSIV.GetPrimaryIdentifier(target) or TSIV.SafeString(payload.identifier, 80)
    if identifier == '' then return { lines = { 'A player ID or identifier is required.' } } end
    local rows = playerRows(identifier, 100)
    local lines = { ('identifier: %s'):format(identifier), ('records: %d'):format(#rows) }
    for _, row in ipairs(rows) do lines[#lines + 1] = ('[%s] %s'):format(TSIV.FormatTimestamp(row.at or row.created_at), row.message or '') end
    local tags = playerTags(identifier)
    lines[#lines + 1] = ('active tags: %d'):format(#tags)
    for _, tag in ipairs(tags) do
        lines[#lines + 1] = ('tag: %s%s'):format(tag.content, tag.expires_at and tag.expires_at > 0
            and (' (expires %s)'):format(TSIV.FormatTimestamp(tag.expires_at)) or ' (permanent)')
    end
    local relationships = {}
    if TSIV.Storage.UsingMysql() then
        relationships = TSIV.Storage.Query(([[SELECT related_identifier, related_name, note FROM `%s` WHERE identifier = ? OR related_identifier = ?]]):format(Config.database.relationshipsTable), { identifier, identifier }) or {}
    else
        for _, row in ipairs(store('relationships')) do
            if row.identifier == identifier or row.related_identifier == identifier then relationships[#relationships + 1] = row end
        end
    end
    lines[#lines + 1] = ('relationships: %d'):format(#relationships)
    for _, row in ipairs(relationships) do lines[#lines + 1] = ('linked: %s %s'):format(row.related_name or row.related_identifier, row.note or '') end
    local bans = Bans.List(identifier, 100)
    lines[#lines + 1] = ('previous bans: %d'):format(#bans)
    return { title = 'Player rating', lines = lines }
end)

RegisterCommand('rating', function(src, args)
    if not permitted(src, 'player.rating') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target then
        TSIV.Notify(src, 'usage: /rating <server id>', 'error')
        return
    end
    local identifier = TSIV.GetPrimaryIdentifier(target)
    local rows = playerRows(identifier, 100)
    local tags = playerTags(identifier)
    local lines = {
        ('player: %s'):format(TSIV.Describe(target)),
        ('identifier: %s'):format(identifier),
        ('records: %d'):format(#rows),
        ('active tags: %d'):format(#tags),
    }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('[%s] %s'):format(TSIV.FormatTimestamp(row.at or row.created_at), row.message or '')
    end
    for _, tag in ipairs(tags) do
        lines[#lines + 1] = ('tag: %s'):format(tag.content)
    end
    TSIV.ConsoleBlock(src, 'Player rating', lines)
end, false)

RegisterCommand('watchlist', function(src, args)
    if not permitted(src, 'player.watchlist') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target then TSIV.Notify(src, 'usage: /watchlist <server id> [note]', 'error'); return end
    Records.AddWatch(target, table.concat(args, ' ', 2), TSIV.GetName(src))
    TSIV.Notify(src, 'Player added to the watchlist.', 'success')
end, false)

RegisterCommand('player_tag', function(src, args)
    if not permitted(src, 'player.tags') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target or not args[2] then TSIV.Notify(src, 'usage: /player_tag <id> <duration|permanent> <content>', 'error'); return end
    local seconds = duration(args[2])
    if not seconds then TSIV.Notify(src, 'Invalid duration.', 'error'); return end
    if addTag(src, target, seconds > 0 and os.time() + seconds or 0, table.concat(args, ' ', 3)) then
        TSIV.Notify(src, 'Player tag added.', 'success')
    else
        TSIV.Notify(src, 'The player tag could not be stored. Check the server console.', 'error')
    end
end, false)

AddEventHandler('playerJoining', function()
    local src = source
    local identifier, ids, name = playerData(src)
    local watch = findWatch(identifier)
    if watch then
        TSIV.StaffBroadcast('superadmin', ('Watchlist login: %s joined (server ID %d)'):format(name, src))
        for _, member in ipairs(TSIV.GetStaff('superadmin')) do
            TriggerClientEvent(TSIV.Events.watchlist, member.source, name, src)
        end
    end
    local aliases = store('aliases')
    local seen = false
    if TSIV.Storage.UsingMysql() then
        seen = TSIV.Storage.Single(([[
            SELECT id FROM `%s` WHERE license = ? AND steam = ? AND name = ? LIMIT 1
        ]]):format(Config.database.aliasesTable), { identifier, ids.steam or '', name }) ~= nil
    else
        for _, row in ipairs(aliases) do
            if row.license == identifier and row.name == name and row.steam == (ids.steam or '') then seen = true break end
        end
    end
    if not seen then
        if TSIV.Storage.UsingMysql() then
            TSIV.Storage.Insert(([[
                INSERT INTO `%s` (license, steam, name, at) VALUES (?, ?, ?, ?)
            ]]):format(Config.database.aliasesTable), { identifier, ids.steam or '', name, os.time() })
        else
            aliases[#aliases + 1] = { license = identifier, steam = ids.steam or '', name = name, at = os.time() }
            TSIV.Storage.MarkDirty('aliases')
        end
    end
end)

TSIV.RegisterRequest('player.aliases', 'player.aliases', function(_, payload)
    local target = TSIV.ResolveTarget(payload.target)
    local license = target and TSIV.GetIdentifiers(target).license or TSIV.SafeString(payload.license, 80)
    if not license or license == '' then return { lines = { 'A player ID is required.' } } end
    local rows
    if TSIV.Storage.UsingMysql() then
        rows = TSIV.Storage.Query(([[
            SELECT steam, name, at FROM `%s` WHERE license = ? ORDER BY id DESC
        ]]):format(Config.database.aliasesTable), { license }) or {}
    else
        rows = {}
        for _, row in ipairs(store('aliases')) do if row.license == license then rows[#rows + 1] = row end end
    end
    local lines = { 'license: ' .. license }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('[%s] %s / %s'):format(TSIV.FormatTimestamp(row.at), row.name, row.steam ~= '' and row.steam or 'no steam')
    end
    if #rows == 0 then lines[#lines + 1] = 'No aliases recorded yet.' end
    return { title = 'Player aliases', lines = lines }
end)

TSIV.RegisterAction('player.link', 'player.relationships', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    local related = TSIV.ResolveTarget(payload.related)
    if not target or not related or target == related then
        TSIV.Notify(src, 'Enter two different online player IDs.', 'error'); return
    end
    local row = {
        identifier = TSIV.GetPrimaryIdentifier(target),
        related_identifier = TSIV.GetPrimaryIdentifier(related),
        related_name = TSIV.GetName(related), note = TSIV.SafeString(payload.note, 160),
        created_at = os.time(), added_by = actor(src),
    }
    if TSIV.Storage.UsingMysql() then
        TSIV.Storage.Insert(([[
            INSERT INTO `%s` (identifier, related_identifier, related_name, note, created_at, added_by)
            VALUES (?, ?, ?, ?, ?, ?)
        ]]):format(Config.database.relationshipsTable), {
            row.identifier, row.related_identifier, row.related_name, row.note, row.created_at, row.added_by,
        })
    else
        local rows = store('relationships'); rows[#rows + 1] = row
        TSIV.Storage.MarkDirty('relationships'); TSIV.Storage.Flush('relationships')
    end
    Logs.Staff(src, ('Linked %s with %s'):format(TSIV.Describe(target), TSIV.Describe(related)), target)
    TSIV.Notify(src, 'Players linked.', 'success')
end)
