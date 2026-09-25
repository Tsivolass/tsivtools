TSIV.Logs = {}

local Logs = TSIV.Logs
local nextId = 1

local function fileStore()
    return TSIV.Storage.Get('logs')
end

local function initFileIds()
    local store = fileStore()
    for _, entry in ipairs(store) do
        if entry.id and entry.id >= nextId then
            nextId = entry.id + 1
        end
    end
end

CreateThread(function()
    TSIV.Storage.WaitReady()
    if not TSIV.Storage.UsingMysql() then
        initFileIds()
    end
end)

function Logs.Write(entry)
    local category = entry.category or 'staff'
    if     Config.Logging.categories[category] == false then return end

    local record = {
        id = nextId,
        category = category,
        at = os.time(),
        actor = entry.actor or '',
        actorName = TSIV.SafeString(entry.actorName or '', 48),
        target = entry.target or '',
        targetName = TSIV.SafeString(entry.targetName or '', 48),
        message = TSIV.SafeString(entry.message or '', 400),
        data = entry.data,
    }
    nextId = nextId + 1

    if TSIV.Storage.UsingMysql() then
        TSIV.Storage.InsertLater(([[
            INSERT INTO `%s` (category, created_at, actor, actor_name, target, target_name, message, data)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]]):format(Config.Database.logTable), {
            record.category, record.at, record.actor, record.actorName,
            record.target, record.targetName, record.message,
            record.data and json.encode(record.data) or nil,
        })
    else
        local store = fileStore()
        store[#store + 1] = record
        local overflow = #store - Config.Logging.maxEntries
        if overflow > 0 then
            local trimmed = {}
            for index = overflow + 1, #store do
                trimmed[#trimmed + 1] = store[index]
            end
            for key in pairs(store) do store[key] = nil end
            for index, value in ipairs(trimmed) do store[index] = value end
        end
        TSIV.Storage.MarkDirty('logs')
    end

    TSIV.Discord.Send(category, record)
    return record
end

function Logs.Staff(src, message, target, data)
    local targetIdentifier, targetName = '', ''
    if type(target) == 'number' then
        targetIdentifier = TSIV.GetPrimaryIdentifier(target)
        targetName = TSIV.GetName(target)
    elseif type(target) == 'string' then
        targetIdentifier = target
    elseif type(target) == 'table' then
        targetIdentifier = target.identifier or ''
        targetName = target.name or ''
    end

    return Logs.Write({
        category = 'staff',
        message = message,
        actor = src ~= 0 and TSIV.GetPrimaryIdentifier(src) or 'console',
        actorName = src ~= 0 and TSIV.GetName(src) or 'server console',
        target = targetIdentifier,
        targetName = targetName,
        data = data,
    })
end

function Logs.Search(query, limit, category)
    query = TSIV.SafeString(query, 64):lower()
    limit = TSIV.ToInt(limit, 1, 100) or 25

    local results = {}

    if TSIV.Storage.UsingMysql() then
        local like = '%' .. query .. '%'
        local sql = ([[
            SELECT id, category, created_at AS at, actor, actor_name AS actorName,
                   target, target_name AS targetName, message, data
            FROM `%s`
            WHERE (LOWER(actor) LIKE ? OR LOWER(target) LIKE ?
                   OR LOWER(actor_name) LIKE ? OR LOWER(target_name) LIKE ?)
        ]]):format(Config.Database.logTable)
        local params = { like, like, like, like }
        if category and category ~= 'all' then
            sql = sql .. ' AND category = ?'
            params[#params + 1] = category
        end
        sql = sql .. ' ORDER BY id DESC LIMIT ' .. limit
        results = TSIV.Storage.Query(sql, params) or {}
    else
        local store = fileStore()
        for index = #store, 1, -1 do
            local entry = store[index]
            local matches = query == ''
                or (entry.actor or ''):lower():find(query, 1, true) ~= nil
                or (entry.target or ''):lower():find(query, 1, true) ~= nil
                or (entry.actorName or ''):lower():find(query, 1, true) ~= nil
                or (entry.targetName or ''):lower():find(query, 1, true) ~= nil
            if matches and (not category or category == 'all' or entry.category == category) then
                results[#results + 1] = entry
                if #results >= limit then break end
            end
        end
    end

    return results
end

function Logs.Summary(query)
    local entries = Logs.Search(query, 100)
    local counts = {}
    for _, entry in ipairs(entries) do
        counts[entry.category] = (counts[entry.category] or 0) + 1
    end
    return counts, #entries
end

TSIV.RegisterRequest('logs.lookup', 'staff.logs', function(src, payload)
    local query = TSIV.SafeString(payload.query, 64)
    if query == '' then return { lines = { 'Nothing to search for !' } } end

    local category = TSIV.SafeString(payload.category, 16)
    local entries = Logs.Search(query, payload.limit, category ~= '' and category or nil)
    local counts, total = Logs.Summary(query)

    local lines = {}
    if total == 0 then
        lines[#lines + 1] = ('No TsivTools records found for "%s" !'):format(query)
    else
        local summary = {}
        for name, count in pairs(counts) do
            summary[#summary + 1] = ('%s x%d'):format(name, count)
        end
        table.sort(summary)
        lines[#lines + 1] = ('%d record(s) in the last 100: %s'):format(total, table.concat(summary, ', '))
        lines[#lines + 1] = ('-'):rep(60)

        for _, entry in ipairs(entries) do
            local data = entry.data
            if type(data) == 'string' then
                local ok, decoded = pcall(json.decode, data)
                data = ok and decoded or nil
            end
            lines[#lines + 1] = ('[%s] %-9s %s'):format(
                TSIV.FormatTimestamp(entry.at), entry.category, entry.message)
            local who = {}
            if entry.actor ~= '' then
                who[#who + 1] = ('by %s %s'):format(entry.actorName ~= '' and entry.actorName or '?', entry.actor)
            end
            if entry.target ~= '' then
                who[#who + 1] = ('on %s %s'):format(entry.targetName ~= '' and entry.targetName or '?', entry.target)
            end
            if #who > 0 then
                lines[#lines + 1] = ('           %s'):format(table.concat(who, '  |  '))
            end
        end
    end

    Logs.Staff(src, ('Looked up logs for "%s"'):format(query))

    return { title = ('TsivTools log lookup: %s'):format(query), lines = lines }
end)

TSIV.RegisterRequest('logs.recent', 'staff.logs', function(src, payload)
    local category = TSIV.SafeString(payload.category, 16)
    if category == '' then category = 'all' end
    local entries = Logs.Search('', payload.limit, category)
    local lines = {}
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = ('[%s] %-9s %s%s'):format(
            TSIV.FormatTimestamp(entry.at),
            entry.category,
            entry.message,
            entry.actorName ~= '' and ('  (by %s)'):format(entry.actorName) or '')
    end
    if #lines == 0 then
        lines[1] = 'Nothing logged yet !'
    end
    return { title = ('TsivTools recent logs (%s)'):format(category), lines = lines }
end)

AddEventHandler('playerJoining', function()
    local src = source
    Logs.Write({
        category = 'connect',
        message = ('%s joined'):format(TSIV.Describe(src)),
        actor = TSIV.GetPrimaryIdentifier(src),
        actorName = TSIV.GetName(src),
        data = { steam = TSIV.GetSteamId(src) },
    })
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    Logs.Write({
        category = 'connect',
        message = ('%s left (%s)'):format(TSIV.Describe(src), TSIV.SafeString(reason or '', 80)),
        actor = TSIV.GetPrimaryIdentifier(src),
        actorName = TSIV.GetName(src),
    })
end)
