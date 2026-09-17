TSIV.Bans = {}

local Bans = TSIV.Bans
local nextId = 1

local function fileStore()
    return TSIV.Storage.Get('bans')
end

CreateThread(function()
    Wait(500)
    if not TSIV.Storage.UsingMysql() then
        for _, ban in ipairs(fileStore()) do
            if ban.id and ban.id >= nextId then nextId = ban.id + 1 end
        end
    end
end)

local function isExpired(ban)
    return ban.expires_at and ban.expires_at > 0 and ban.expires_at <= os.time()
end

function Bans.Add(identifiers, name, reason, minutes, bannedBy)
    if type(identifiers) == 'string' then identifiers = { identifiers } end
    if not identifiers or #identifiers == 0 then return nil end

    local expires = 0
    minutes = tonumber(minutes) or 0
    if minutes > 0 then
        expires = os.time() + math.floor(minutes * 60)
    end

    local ban = {
        id = nextId,
        identifier = identifiers[1],
        identifiers = identifiers,
        name = TSIV.SafeString(name or '', 48),
        reason = TSIV.SafeString(reason or 'No reason given', 200),
        banned_by = TSIV.SafeString(bannedBy or 'TsivTools', 48),
        created_at = os.time(),
        expires_at = expires,
        active = 1,
    }
    nextId = nextId + 1

    if TSIV.Storage.UsingMysql() then
        local id = TSIV.Storage.Insert(([[
            INSERT INTO `%s` (identifier, identifiers, name, reason, banned_by, created_at, expires_at, active)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1)
        ]]):format(Config.Database.banTable), {
            ban.identifier, json.encode(ban.identifiers), ban.name, ban.reason,
            ban.banned_by, ban.created_at, ban.expires_at,
        })
        ban.id = id or ban.id
    else
        local store = fileStore()
        store[#store + 1] = ban
        TSIV.Storage.MarkDirty('bans')
        TSIV.Storage.Flush('bans')
    end

    TSIV.Logs.Write({
        category = 'ban',
        message = ('Banned %s for %s - %s'):format(
            ban.name ~= '' and ban.name or ban.identifier,
            TSIV.FormatDuration(minutes), ban.reason),
        actor = bannedBy or 'TsivTools',
        actorName = bannedBy or 'TsivTools',
        target = ban.identifier,
        targetName = ban.name,
        data = { banId = ban.id, expires = ban.expires_at, identifiers = ban.identifiers },
    })

    return ban
end

function Bans.Find(identifiers)
    if TSIV.Storage.UsingMysql() then
        for _, identifier in pairs(identifiers) do
            local row = TSIV.Storage.Single(([[
                SELECT * FROM `%s` WHERE identifier = ? AND active = 1 LIMIT 1
            ]]):format(Config.Database.banTable), { identifier })
            if row then
                if isExpired(row) then
                    Bans.Remove(row.id)
                else
                    return row
                end
            end
            local row2 = TSIV.Storage.Single(([[
                SELECT * FROM `%s` WHERE active = 1 AND identifiers LIKE ? LIMIT 1
            ]]):format(Config.Database.banTable), { '%' .. identifier .. '%' })
            if row2 then
                if isExpired(row2) then
                    Bans.Remove(row2.id)
                else
                    return row2
                end
            end
        end
        return nil
    end

    local store = fileStore()
    for _, ban in ipairs(store) do
        if ban.active == 1 then
            if isExpired(ban) then
                ban.active = 0
                TSIV.Storage.MarkDirty('bans')
            else
                for _, stored in ipairs(ban.identifiers or { ban.identifier }) do
                    for _, identifier in pairs(identifiers) do
                        if stored == identifier then
                            return ban
                        end
                    end
                end
            end
        end
    end
    return nil
end

function Bans.Remove(banId)
    banId = tonumber(banId)
    if not banId then return nil end

    if TSIV.Storage.UsingMysql() then
        local row = TSIV.Storage.Single(([[SELECT * FROM `%s` WHERE id = ?]]):format(Config.Database.banTable), { banId })
        if not row then return nil end
        TSIV.Storage.Execute(([[UPDATE `%s` SET active = 0 WHERE id = ?]]):format(Config.Database.banTable), { banId })
        return row
    end

    for _, ban in ipairs(fileStore()) do
        if ban.id == banId and ban.active == 1 then
            ban.active = 0
            TSIV.Storage.MarkDirty('bans')
            TSIV.Storage.Flush('bans')
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

    if TSIV.Storage.UsingMysql() then
        local rows = TSIV.Storage.Query(([[
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
    for _, identifier in pairs(TSIV.GetIdentifiers(target)) do
        identifiers[#identifiers + 1] = identifier
    end

    local ban = Bans.Add(identifiers, TSIV.GetName(target), reason, minutes, bannedBy)
    if not ban then return nil end

    DropPlayer(target, Config.Bans.message:format(
        ban.reason,
        ban.expires_at > 0 and TSIV.FormatTimestamp(ban.expires_at) or Config.Bans.permanentText,
        tostring(ban.id)))

    return ban
end


AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local identifiers = {}
    for _, kind in ipairs(Config.Bans.identifierTypes) do
        local identifier = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, kind) or nil
        if identifier then identifiers[#identifiers + 1] = identifier end
    end

    if #identifiers == 0 then
        for _, identifier in pairs(TSIV.GetIdentifiers(src)) do
            identifiers[#identifiers + 1] = identifier
        end
    end

    local ban = Bans.Find(identifiers)
    if ban then
        local expiry = (ban.expires_at and ban.expires_at > 0)
            and TSIV.FormatTimestamp(ban.expires_at) or Config.Bans.permanentText
        deferrals.done(Config.Bans.message:format(ban.reason, expiry, tostring(ban.id)))
        print(('%srefused a banned connection: %s (ban %s)'):format(
            Config.ConsolePrefix, ban.identifier, tostring(ban.id)))
        return
    end

    deferrals.done()
end)


TSIV.RegisterAction('player.ban', 'player.ban', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player isnt online !', 'error')
        return
    end


    local minutes = TSIV.ToInt(payload.minutes, 0, 60 * 24 * 3650) or 0
    local reason = TSIV.SafeString(payload.reason, 200)
    if reason == '' then reason = 'No reason given' end

    local targetName = TSIV.GetName(target)
    local ban = Bans.BanPlayer(target, reason, minutes, TSIV.GetName(src))
    if not ban then
        TSIV.Notify(src, 'The ban could not be stored !!', 'error')
        return
    end

    TSIV.Notify(src, ('Banned %s (%s) - ban ID %s'):format(targetName, TSIV.FormatDuration(minutes), ban.id), 'success')
    TSIV.Logs.Staff(src, ('Banned %s for %s - %s'):format(targetName, TSIV.FormatDuration(minutes), reason), ban.identifier)
    TSIV.StaffBroadcast('mod', ('%s%s banned %s (%s)'):format(Config.Prefix, TSIV.GetName(src), targetName, TSIV.FormatDuration(minutes)))
end)

TSIV.RegisterAction('player.unban', 'player.unban', function(src, payload)
    local ban = Bans.Remove(payload.banId)
    if not ban then
        TSIV.Notify(src, 'No active ban with that ID !', 'error')
        return
    end
    TSIV.Notify(src, ('removed ban %s (%s)'):format(ban.id, ban.name ~= '' and ban.name or ban.identifier), 'success')
    TSIV.Logs.Staff(src, ('removed ban %s on %s'):format(ban.id, ban.identifier), ban.identifier)
end)

TSIV.RegisterRequest('bans.list', 'player.unban', function(src, payload)
    local query = TSIV.SafeString(payload.query, 64)
    local bans = Bans.List(query, 40)
    local out = {}
    for _, ban in ipairs(bans) do
        out[#out + 1] = {
            id = ban.id,
            name = ban.name,
            identifier = ban.identifier,
            reason = ban.reason,
            bannedBy = ban.banned_by,
            expires = ban.expires_at,
            expiresText = (ban.expires_at and ban.expires_at > 0)
                and TSIV.FormatTimestamp(ban.expires_at) or Config.Bans.permanentText,
        }
    end
    return out
end)
