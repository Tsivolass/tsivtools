local actions = {}
local requests = {}
local rankCache = {}
local rateLimit = {}

function tsivtools.GetIdentifiers(src)
    local out = {}
    local count = GetNumPlayerIdentifiers(src)
    for index = 0, count - 1 do
        local identifier = GetPlayerIdentifier(src, index)
        if identifier then
            local kind = identifier:match('^(%w+):')
            if kind then
                out[kind] = identifier
            end
        end
    end
    return out
end

function tsivtools.GetPrimaryIdentifier(src)
    local ids = tsivtools.GetIdentifiers(src)
    return ids.license or ids.steam or ids.discord or ids.fivem or ('src:' .. src)
end

function tsivtools.GetSteamId(src)
    local ids = tsivtools.GetIdentifiers(src)
    return ids.steam or 'no steam id'
end

function tsivtools.GetName(src)
    local name = GetPlayerName(src)
    return name and tsivtools.SafeString(name, 48) or ('unknown (' .. tostring(src) .. ')')
end

function tsivtools.Describe(src)
    return ('%s (id %s)'):format(tsivtools.GetName(src), src)
end

function tsivtools.ResolveTarget(value)
    local id = tsivtools.ToInt(value, 1, 65535)
    if not id then return nil end
    if GetPlayerName(id) == nil then return nil end
    return id
end

local function frameworkRank(src)
    if Config.framework == 'esx' then
        local ok, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if not ok or not esx then return nil end
        local player = esx.GetPlayerFromId(src)
        if not player then return nil end
        return Config.frameworkgroupmap[player.getGroup()]
    elseif Config.framework == 'qb' then
        local ok, qb = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if not ok or not qb then return nil end
        local player = qb.Functions.GetPlayer(src)
        if not player then return nil end
        local group = qb.Functions.GetPermission and qb.Functions.GetPermission(src) or nil
        return group and Config.frameworkgroupmap[group] or nil
    end
    return nil
end

function tsivtools.GetRank(src)
    if src == 0 then
        local ranks = tsivtools.Ranks()
        return ranks[#ranks].name
    end

    if rankCache[src] ~= nil then return rankCache[src] or nil end

    local best, bestLevel = nil, 0

    local identifiers = tsivtools.GetIdentifiers(src)
    for _, identifier in pairs(identifiers) do
        local rank = Config.staff[identifier]
        if rank and tsivtools.RankLevel(rank) > bestLevel then
            best, bestLevel = rank, tsivtools.RankLevel(rank)
        end

        local stored = tsivtools.StaffStore()[identifier]
        if stored and tsivtools.RankLevel(stored) > bestLevel then
            best, bestLevel = stored, tsivtools.RankLevel(stored)
        end
    end

    if Config.useacepermissions then
        for _, rank in ipairs(tsivtools.Ranks()) do
            local ace = ('%s.%s'):format(Config.aceprefix, rank.name)
            if IsPlayerAceAllowed(src, ace) and rank.level > bestLevel then
                best, bestLevel = rank.name, rank.level
            end
        end
    end

    if Config.framework ~= 'none' then
        local rank = frameworkRank(src)
        if rank and tsivtools.RankLevel(rank) > bestLevel then
            best, bestLevel = rank, tsivtools.RankLevel(rank)
        end
    end

    rankCache[src] = best or false
    return best
end

function tsivtools.ClearRankCache(src)
    if src then
        rankCache[src] = nil
    else
        rankCache = {}
    end
end

function tsivtools.Can(src, key)
    local rank = tsivtools.GetRank(src)
    if not rank then return false end
    return tsivtools.HasPermission(rank, key)
end

function tsivtools.OutranksTarget(src, target)
    if src == 0 or src == target then return true end
    return tsivtools.RankLevel(tsivtools.GetRank(src)) > tsivtools.RankLevel(tsivtools.GetRank(target))
end

function tsivtools.GetStaff(minRank)
    local minLevel = minRank and tsivtools.RankLevel(minRank) or 1
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local rank = tsivtools.GetRank(src)
        if rank and tsivtools.RankLevel(rank) >= minLevel then
            out[#out + 1] = {
                source = src,
                name = tsivtools.GetName(src),
                rank = rank,
                rankLabel = tsivtools.RankLabel(rank),
                level = tsivtools.RankLevel(rank),
                identifier = tsivtools.GetPrimaryIdentifier(src),
                steam = tsivtools.GetSteamId(src),
            }
        end
    end
    table.sort(out, function(a, b)
        if a.level == b.level then return a.name < b.name end
        return a.level > b.level
    end)
    return out
end

function tsivtools.Notify(src, message, kind)
    if src == 0 then
        print(Config.consoleprefix .. message)
        return
    end
    TriggerClientEvent(tsivtools.Events.notify, src, message, kind or 'info')
end

function tsivtools.Console(src, message, colour)
    if src == 0 then
        print(Config.consoleprefix .. message)
        return
    end
    TriggerClientEvent(tsivtools.Events.console, src, message, colour)
end

function tsivtools.ConsoleBlock(src, title, lines)
    if src == 0 then
        print(Config.consoleprefix .. title)
        for _, line in ipairs(lines) do print('  ' .. line) end
        return
    end
    TriggerClientEvent(tsivtools.Events.console, src, { title = title, lines = lines })
end

function tsivtools.StaffBroadcast(minRank, message, consoleLines)
    for _, member in ipairs(tsivtools.GetStaff(minRank)) do
        if consoleLines then
            tsivtools.ConsoleBlock(member.source, message or 'tsivtools alert', consoleLines)
            TriggerClientEvent(tsivtools.Events.alert, member.source, nil)
        elseif message then
            TriggerClientEvent(tsivtools.Events.alert, member.source, message)
        end
    end

    local plain = (message or ''):gsub('%^%d', '')
    plain = plain:gsub('^' .. Config.prefix:gsub('%^%d', ''):gsub('(%W)', '%%%1'), '')
    print(('%s%s'):format(Config.consoleprefix, plain))
    if consoleLines then
        for _, line in ipairs(consoleLines) do print('  ' .. line) end
    end
end

function tsivtools.RegisterAction(name, permission, handler)
    actions[name] = { permission = permission, handler = handler }
end

function tsivtools.RegisterRequest(name, permission, handler)
    requests[name] = { permission = permission, handler = handler }
end

local forged = {}

local function forgedEvent(src, name)
    local rules = Config.anticheat.forgedEvents
    if not rules.enabled then return end

    local now = GetGameTimer() / 1000.0
    local entry = forged[src]
    if not entry or now - entry.first > 600.0 then
        entry = { first = now, count = 0 }
        forged[src] = entry
    end
    entry.count = entry.count + 1

    local detail = {
        ('event     : %s'):format(tsivtools.SafeString(name, 40)),
        ('attempts  : %d in %.0f second(s)'):format(entry.count, now - entry.first),
        'note      : the menu never sends this without a staff rank',
    }
    if entry.count >= rules.strikes then
        forged[src] = nil
        tsivtools.AntiCheat.Punish(src, rules.action, rules.reason, rules.banLength, detail)
    elseif entry.count == 1 then
        tsivtools.AntiCheat.Punish(src, 'alert', rules.reason, 0, detail)
    end
end

local protected = {
    ['player.bring']            = true,
    ['player.slay']             = true,
    ['player.freeze']           = true,
    ['player.kick']             = true,
    ['player.warn']             = true,
    ['player.setrank']          = true,
    ['player.ban']              = true,
    ['player.tag']              = true,
    ['cleanup.player']          = true,
    ['watchlist.add']           = true,
    ['security.waveshield.ban'] = true,
}

local function allowRate(src)
    local now = GetGameTimer() / 1000.0
    local bucket = rateLimit[src]
    if not bucket or now - bucket.start > 10.0 then
        rateLimit[src] = { start = now, count = 1 }
        return true
    end
    bucket.count = bucket.count + 1
    if bucket.count > 40 then
        if bucket.count == 41 then
            print(('%s%s is sending events far too quickly and is being throttled')
                :format(Config.consoleprefix, tsivtools.Describe(src)))
        end
        return false
    end
    return true
end

RegisterNetEvent(tsivtools.Events.action, function(name, payload)
    local src = source
    if type(name) ~= 'string' then return end
    if not allowRate(src) then return end

    if not tsivtools.GetRank(src) then
        forgedEvent(src, name)
        return
    end

    local entry = actions[name]
    if not entry then
        print(('%s%s asked for the unknown action "%s"'):format(Config.consoleprefix, tsivtools.Describe(src), tsivtools.SafeString(name, 40)))
        return
    end

    if entry.permission and not tsivtools.Can(src, entry.permission) then
        tsivtools.Notify(src, 'You do not have permission to do that !!', 'error')
        print(('%s%s tried to use "%s" without the %s permission')
            :format(Config.consoleprefix, tsivtools.Describe(src), name, entry.permission))
        return
    end

    payload = type(payload) == 'table' and payload or {}
    local target = protected[name] and tsivtools.ResolveTarget(payload.target)
    if target and not tsivtools.OutranksTarget(src, target) then
        tsivtools.Notify(src, 'That player is your rank or higher !', 'error')
        return
    end

    local ok, err = pcall(entry.handler, src, payload)
    if not ok then
        print(('%saction "%s" failed: %s'):format(Config.consoleprefix, name, err))
        tsivtools.Notify(src, 'That action failed! report to dev !!', 'error')
    end
end)

RegisterNetEvent(tsivtools.Events.request, function(name, requestId, payload)
    local src = source
    if type(name) ~= 'string' or type(requestId) ~= 'number' then return end
    if not allowRate(src) then return end

    if not tsivtools.GetRank(src) then
        forgedEvent(src, name)
        TriggerClientEvent(tsivtools.Events.response, src, requestId, nil)
        return
    end

    local entry = requests[name]
    if not entry then return end

    if entry.permission and not tsivtools.Can(src, entry.permission) then
        TriggerClientEvent(tsivtools.Events.response, src, requestId, nil)
        return
    end

    local ok, result = pcall(entry.handler, src, type(payload) == 'table' and payload or {})
    if not ok then
        print(('%srequest "%s" failed: %s'):format(Config.consoleprefix, name, result))
        result = nil
    end
    TriggerClientEvent(tsivtools.Events.response, src, requestId, result)
end)

local function sendPermissions(src)
    local rank = tsivtools.GetRank(src)
    if not rank then
        TriggerClientEvent(tsivtools.Events.permissions, src, nil)
        return
    end

    local granted = {}
    for key in pairs(Config.permissions) do
        if tsivtools.HasPermission(rank, key) then
            granted[key] = true
        end
    end

    TriggerClientEvent(tsivtools.Events.permissions, src, {
        rank = rank,
        rankLabel = tsivtools.RankLabel(rank),
        level = tsivtools.RankLevel(rank),
        granted = granted,
        propLogging = tsivtools.PropLoggingEnabled(),
        traffic = tsivtools.TrafficState(),
    })
end

tsivtools.SendPermissions = sendPermissions

RegisterNetEvent(tsivtools.Events.ready, function()
    local src = source
    if not allowRate(src) then return end
    sendPermissions(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    rankCache[src] = nil
    rateLimit[src] = nil
    forged[src] = nil
end)

RegisterCommand('tsivtools_whoami', function(src, args)
    local target = tsivtools.ResolveTarget(args[1]) or (src ~= 0 and src or nil)
    if not target then
        print(('%susage: tsivtools_whoami <user id>'):format(Config.consoleprefix))
        return
    end

    if src ~= 0 and not tsivtools.Can(src, 'player.identifiers') and src ~= target then
        return
    end

    local lines = { ('rank: %s'):format(tsivtools.GetRank(target) or 'none') }
    for kind, identifier in pairs(tsivtools.GetIdentifiers(target)) do
        lines[#lines + 1] = ('%s = %s'):format(kind, identifier)
    end

    if src == 0 then
        print(('%sidentifiers for %s'):format(Config.consoleprefix, tsivtools.Describe(target)))
        for _, line in ipairs(lines) do print('  ' .. line) end
    else
        tsivtools.ConsoleBlock(src, ('identifiers for %s'):format(tsivtools.Describe(target)), lines)
    end
end, false)

RegisterCommand('tsivtools_reload', function(src)
    if src ~= 0 then
        if not tsivtools.Can(src, 'player.setrank') then return end
    end
    tsivtools.ClearRankCache()
    for _, player in ipairs(GetPlayers()) do
        sendPermissions(tonumber(player))
    end
    print(('%sranks re-evaluated for every online player'):format(Config.consoleprefix))
end, false)
